import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/workout_service.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  final List<String> selectedExerciseIds;

  const ExerciseSelectionScreen({
    super.key,
    required this.selectedExerciseIds,
  });

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  List<dynamic> _allExercises = [];
  List<dynamic> _filteredExercises = [];
  final Set<String> _selectedIds = {};
  Set<String> _favoriteIds = {};
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  String _searchQuery = '';
  String? _selectedMuscleGroup;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _muscleGroups = [
    'CHEST', 'BACK', 'LEGS', 'ARMS', 'SHOULDERS', 'CORE', 'CARDIO',
  ];

  final Map<String, String> _muscleGroupLabels = {
    'CHEST': 'Peito', 'BACK': 'Costas', 'LEGS': 'Pernas',
    'ARMS': 'Braços', 'SHOULDERS': 'Ombros', 'CORE': 'Core', 'CARDIO': 'Cardio',
  };

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.selectedExerciseIds);
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final results = await Future.wait([
        workoutService.getExercises(),
        workoutService.getFavoriteExerciseIds(),
      ]);
      final exercises = results[0];
      final favIds = results[1] as List<String>;
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _favoriteIds = Set<String>.from(favIds);
          _filterExercises();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizeString(String text) {
    const withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    String result = text;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result.toLowerCase();
  }

  void _filterExercises() {
    setState(() {
      final searchWords = _normalizeString(_searchQuery)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      _filteredExercises = _allExercises.where((exercise) {
        final name = _normalizeString(exercise['name'].toString());
        final matchesSearch = searchWords.isEmpty ||
            searchWords.every((word) => name.contains(word));
        final matchesGroup = _selectedMuscleGroup == null ||
            exercise['muscle_group'] == _selectedMuscleGroup;
        final matchesFav =
            !_showFavoritesOnly || _favoriteIds.contains(exercise['id']);
        return matchesSearch && matchesGroup && matchesFav;
      }).toList();
    });
  }

  Future<void> _toggleFavorite(String exerciseId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutService = WorkoutService(authProvider.dio);
    final result = await workoutService.toggleFavoriteExercise(exerciseId);
    if (result != null && mounted) {
      setState(() {
        if (result) {
          _favoriteIds.add(exerciseId);
        } else {
          _favoriteIds.remove(exerciseId);
        }
        _filterExercises();
      });
    }
  }

  void _showCreateExerciseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CreateExerciseSheet(
        onCreated: (exercise) {
          setState(() {
            _allExercises.add(exercise);
            _filterExercises();
          });
        },
      ),
    );
  }

  Future<void> _handleCreateAttempt() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      _showCreateExerciseSheet();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final suggestions = await workoutService.suggestSimilarExercises(query);
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (suggestions.isNotEmpty) {
          _showDidYouMeanSheet(query, suggestions);
        } else {
          _showCreateExerciseSheet();
        }
      }
    } catch (e) {
      debugPrint('Error handling create attempt: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showCreateExerciseSheet();
      }
    }
  }

  void _showDidYouMeanSheet(String query, List<dynamic> suggestions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DidYouMeanSheet(
        query: query,
        suggestions: suggestions,
        onCreateNew: () {
          Navigator.pop(ctx);
          _showCreateExerciseSheet();
        },
        onSelectExisting: (exerciseId) async {
          Navigator.pop(ctx);
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final workoutService = WorkoutService(authProvider.dio);
          final success = await workoutService.addExerciseAlias(exerciseId, query);
          
          if (!mounted) return;
          
          if (success) {
            setState(() {
              _selectedIds.add(exerciseId);
              _searchQuery = '';
              _searchController.clear();
              _filterExercises();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exercício vinculado com sucesso!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro ao vincular exercício.')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Selecionar Exercícios',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(AppConstants.neonAccent),
            tooltip: 'Criar exercício',
            onPressed: _handleCreateAttempt,
          ),
          TextButton(
            onPressed: () {
              final selectedExercises = _allExercises
                  .where((e) => _selectedIds.contains(e['id']))
                  .toList();
              Navigator.pop(context, selectedExercises);
            },
            child: Text(
              'Concluir (${_selectedIds.length})',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.neonAccent),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(AppConstants.cardDark),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterExercises();
                  },
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar exercício...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(AppConstants.primaryDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Favorites chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: _showFavoritesOnly,
                          avatar: Icon(
                            Icons.star,
                            size: 16,
                            color: _showFavoritesOnly ? Colors.black : Colors.amber,
                          ),
                          label: Text('Favoritos'),
                          labelStyle: GoogleFonts.inter(
                            color: _showFavoritesOnly ? Colors.black : Colors.amber,
                            fontWeight: _showFavoritesOnly ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(AppConstants.primaryDark),
                          selectedColor: Colors.amber,
                          checkmarkColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _showFavoritesOnly
                                  ? Colors.amber
                                  : Colors.amber.withOpacity(0.5),
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _showFavoritesOnly = selected;
                              _filterExercises();
                            });
                          },
                        ),
                      ),
                      _buildFilterChip(null, 'Todos'),
                      ..._muscleGroups.map(
                        (group) => _buildFilterChip(
                            group, _muscleGroupLabels[group] ?? group),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      final isSelected = _selectedIds.contains(exercise['id']);
                      final isFavorite = _favoriteIds.contains(exercise['id']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.cardDark),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(AppConstants.neonAccent))
                              : null,
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(exercise['id']);
                              } else {
                                _selectedIds.add(exercise['id']);
                              }
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.primaryDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSelected ? Icons.check : Icons.fitness_center,
                              color: isSelected
                                  ? const Color(AppConstants.neonAccent)
                                  : Colors.grey,
                            ),
                          ),
                          title: Text(
                            exercise['name'],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _muscleGroupLabels[exercise['muscle_group']] ??
                                exercise['muscle_group'] ??
                                'Geral',
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _toggleFavorite(exercise['id']),
                                child: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color: isFavorite ? Colors.amber : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(AppConstants.neonAccent))
                                  : const Icon(Icons.circle_outlined,
                                      color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _selectedMuscleGroup == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: GoogleFonts.inter(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(AppConstants.primaryDark),
        selectedColor: const Color(AppConstants.neonAccent),
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? const Color(AppConstants.neonAccent)
                : const Color(AppConstants.borderColor),
          ),
        ),
        onSelected: (bool selected) {
          setState(() {
            _selectedMuscleGroup = selected ? value : null;
            _filterExercises();
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Create Exercise Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _CreateExerciseSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreated;

  const _CreateExerciseSheet({required this.onCreated});

  @override
  State<_CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends State<_CreateExerciseSheet> {
  final _nameController = TextEditingController();
  final _videoController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Musculação';
  String? _muscleGroup;
  bool _saving = false;

  final List<String> _categories = [
    'Musculação', 'Cardio', 'Funcional', 'Mobilidade', 'Alongamento', 'HIIT',
  ];
  final List<String> _muscleGroups = [
    'CHEST', 'BACK', 'LEGS', 'ARMS', 'SHOULDERS', 'CORE', 'CARDIO',
  ];
  final Map<String, String> _muscleGroupLabels = {
    'CHEST': 'Peito', 'BACK': 'Costas', 'LEGS': 'Pernas',
    'ARMS': 'Braços', 'SHOULDERS': 'Ombros', 'CORE': 'Core', 'CARDIO': 'Cardio',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _videoController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final result = await workoutService.createExercise(
        name: _nameController.text.trim(),
        category: _category,
        muscleGroup: _muscleGroup,
        videoUrl: _videoController.text.trim(),
        description: _descController.text.trim(),
      );
      if (result != null && mounted) {
        widget.onCreated(result);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar exercício: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Novo Exercício',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Nome *'),
          _buildField(_nameController, 'Ex: Supino Reto'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Categoria'),
                    _buildDropdown(
                      value: _category,
                      items: _categories,
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Grupo muscular'),
                    _buildDropdown(
                      value: _muscleGroup,
                      items: _muscleGroups,
                      labels: _muscleGroupLabels,
                      hint: 'Selecionar',
                      onChanged: (v) => setState(() => _muscleGroup = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLabel('Link do YouTube'),
          _buildField(_videoController, 'https://youtube.com/watch?v=...'),
          const SizedBox(height: 12),
          _buildLabel('Descrição'),
          _buildField(_descController, 'Breve descrição...'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || _nameController.text.isEmpty ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text('Criar exercício', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
      );

  Widget _buildField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: GoogleFonts.inter(color: Colors.white),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey),
          filled: true,
          fillColor: const Color(AppConstants.primaryDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    Map<String, String>? labels,
    String? hint,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(AppConstants.primaryDark),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          value: value,
          hint: hint != null
              ? Text(hint, style: GoogleFonts.inter(color: Colors.grey))
              : null,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(AppConstants.cardDark),
          style: GoogleFonts.inter(color: Colors.white),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(labels?[e] ?? e),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Did You Mean Sheet (Synergy mapping)
// ─────────────────────────────────────────────────────────────
class _DidYouMeanSheet extends StatelessWidget {
  final String query;
  final List<dynamic> suggestions;
  final VoidCallback onCreateNew;
  final Function(String) onSelectExisting;

  const _DidYouMeanSheet({
    required this.query,
    required this.suggestions,
    required this.onCreateNew,
    required this.onSelectExisting,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Você quis dizer algum destes?',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Achamos alguns exercícios que se parecem com "$query".',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final item = suggestions[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(AppConstants.borderColor)),
                  ),
                  tileColor: const Color(AppConstants.primaryDark),
                  title: Text(
                    item['name'] ?? '',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(AppConstants.neonAccent)),
                  onTap: () => onSelectExisting(item['id']),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCreateNew,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(AppConstants.neonAccent)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Criar novo do zero',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

