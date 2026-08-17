import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/trainer_service.dart';
import 'student_detail_screen.dart';

class TrainerStudentsScreen extends StatefulWidget {
  const TrainerStudentsScreen({super.key});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _allStudents = [];
  List<User> _filteredStudents = [];
  bool _isLoading = true;
  String? _error;
  int _lastSyncPulse = -1;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    if (_lastSyncPulse != -1 && _lastSyncPulse != auth.syncPulse) {
      _lastSyncPulse = auth.syncPulse;
      _fetchStudents(); // Reload background data
    } else if (_lastSyncPulse == -1) {
      _lastSyncPulse = auth.syncPulse;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      final students = await trainerService.getStudents();

      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar alunos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final name = student.fullName?.toLowerCase() ?? '';
        final email = student.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  void _openStudentActions(User student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Name header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(AppConstants.primaryDark),
                      backgroundImage: student.photoUrl != null
                          ? NetworkImage(student.photoUrl!)
                          : null,
                      child: student.photoUrl == null
                          ? Text(
                              (student.fullName ?? student.email)[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: const Color(AppConstants.neonAccent),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName ?? 'Sem nome',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          student.email,
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 24),
              // Actions
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: Text(
                  'Ver Perfil Completo',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(student: student),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(
                  'Remover Aluno',
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveStudent(student);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveStudent(User student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Remover Aluno?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Isso irá desassociar ${student.fullName ?? student.email} da sua lista. Os treinos criados para ele permanecem.',
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
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      await trainerService.removeStudent(student.id);

      setState(() {
        _allStudents.removeWhere((s) => s.id == student.id);
        _filteredStudents.removeWhere((s) => s.id == student.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.fullName ?? 'Aluno'} removido com sucesso.',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: const Color(AppConstants.neonAccent),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
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
          'Meus Alunos',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(AppConstants.cardDark),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar aluno...',
                hintStyle: GoogleFonts.inter(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(AppConstants.primaryDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: GoogleFonts.inter(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _fetchStudents();
                              },
                              child: const Text('Tentar Novamente'),
                            ),
                          ],
                        ),
                      )
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Text(
                              _allStudents.isEmpty
                                  ? 'Nenhum aluno cadastrado.'
                                  : 'Nenhum aluno encontrado.',
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchStudents,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                return _buildStudentCard(student);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(User student) {
    return Dismissible(
      key: Key(student.id),
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
            Text('Remover',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmRemoveStudent(student);
        return false; // Let _confirmRemoveStudent handle list update
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(AppConstants.cardDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(student: student),
            ),
          ),
          onLongPress: () => _openStudentActions(student),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(AppConstants.primaryDark),
                  backgroundImage: student.photoUrl != null
                      ? NetworkImage(student.photoUrl!)
                      : null,
                  child: student.photoUrl == null
                      ? Text(
                          (student.fullName ?? student.email)[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(AppConstants.neonAccent),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName ?? 'Sem nome',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.email,
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions indicator
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () => _openStudentActions(student),
                  tooltip: 'Ações',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
