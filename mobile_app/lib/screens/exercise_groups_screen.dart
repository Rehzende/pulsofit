import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/workout_service.dart';

class ExerciseGroupsScreen extends StatefulWidget {
  const ExerciseGroupsScreen({super.key});

  @override
  State<ExerciseGroupsScreen> createState() => _ExerciseGroupsScreenState();
}

class _ExerciseGroupsScreenState extends State<ExerciseGroupsScreen> {
  List<dynamic> _groups = [];
  List<dynamic> _allExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final service = WorkoutService(auth.dio);
      final results = await Future.wait([
        service.getExerciseGroups(),
        service.getExercises(),
      ]);
      if (mounted) {
        setState(() {
          _groups = results[0];
          _allExercises = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Novo Grupo',
              style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.inter(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: Protocolo Peito',
                hintStyle: GoogleFonts.inter(color: Colors.grey),
                filled: true,
                fillColor: const Color(AppConstants.primaryDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final service = WorkoutService(auth.dio);
                  final group = await service.createExerciseGroup(name: nameCtrl.text.trim());
                  if (group != null && mounted) {
                    setState(() => _groups.add(group));
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.neonAccent),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Criar grupo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetail(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupDetailScreen(
          group: group,
          allExercises: _allExercises,
          onGroupUpdated: (updated) {
            setState(() {
              final idx = _groups.indexWhere((g) => g['id'] == updated['id']);
              if (idx >= 0) _groups[idx] = updated;
            });
          },
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
        title: Text(
          'Grupos de Exercícios',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: const Color(AppConstants.neonAccent),
            onPressed: _showCreateGroupSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, color: Colors.grey, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum grupo criado',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateGroupSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Criar grupo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppConstants.neonAccent),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final group = _groups[i];
                    final items = (group['items'] as List?) ?? [];
                    return Card(
                      color: const Color(AppConstants.cardDark),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () => _showGroupDetail(group),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryDark),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.layers, color: Color(AppConstants.neonAccent), size: 22),
                        ),
                        title: Text(
                          group['name'],
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${items.length} exercício${items.length != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupSheet,
        backgroundColor: const Color(AppConstants.neonAccent),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Group Detail Screen
// ─────────────────────────────────────────────────────────────
class _GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final List<dynamic> allExercises;
  final Function(Map<String, dynamic>) onGroupUpdated;

  const _GroupDetailScreen({
    required this.group,
    required this.allExercises,
    required this.onGroupUpdated,
  });

  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen> {
  late Map<String, dynamic> _group;
  String? _selectedExerciseId;
  int _sets = 3;
  int _repsMin = 8;
  int _repsMax = 12;
  int _rest = 60;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  Future<void> _addItem() async {
    if (_selectedExerciseId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = _group['id'];
    final items = (_group['items'] as List?) ?? [];
    try {
      final response = await auth.dio.post(
        '${AppConstants.baseUrl}/exercise-groups/$groupId/items',
        data: {
          'exercise_id': _selectedExerciseId,
          'order_index': items.length,
          'sets': _sets,
          'reps_min': _repsMin,
          'reps_max': _repsMax,
          'rest_seconds': _rest,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newItem = response.data;
        // enrich with exercise data
        final exercise = widget.allExercises.firstWhere(
          (e) => e['id'] == _selectedExerciseId,
          orElse: () => {'id': _selectedExerciseId, 'name': 'Exercício'},
        );
        newItem['exercise'] = exercise;
        setState(() {
          final updatedItems = [...items, newItem];
          _group = {..._group, 'items': updatedItems};
          _showAddForm = false;
          _selectedExerciseId = null;
        });
        widget.onGroupUpdated(_group);
      }
    } catch (e) {
      debugPrint('Error adding item: $e');
    }
  }

  Future<void> _removeItem(String itemId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = _group['id'];
    try {
      await auth.dio.delete('${AppConstants.baseUrl}/exercise-groups/$groupId/items/$itemId');
      setState(() {
        final items = (_group['items'] as List).where((i) => i['id'] != itemId).toList();
        _group = {..._group, 'items': items};
      });
      widget.onGroupUpdated(_group);
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_group['items'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          _group['name'],
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty && !_showAddForm
                ? Center(
                    child: Text(
                      'Nenhum exercício no grupo.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...items.asMap().entries.map((entry) {
                        final item = entry.value;
                        final exercise = item['exercise'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.cardDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise?['name'] ?? 'Exercício',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['sets']}x  ${item['reps_min']}–${item['reps_max']} rep  •  ${item['rest_seconds']}s descanso',
                                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _removeItem(item['id']),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),

          // Add item form
          if (_showAddForm)
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Color(AppConstants.cardDark),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adicionar exercício',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedExerciseId,
                    hint: Text('Selecionar exercício', style: GoogleFonts.inter(color: Colors.grey)),
                    dropdownColor: const Color(AppConstants.cardDark),
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(AppConstants.primaryDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: widget.allExercises.map<DropdownMenuItem<String>>((e) {
                      return DropdownMenuItem(value: e['id'] as String, child: Text(e['name'] as String));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedExerciseId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _numField('Séries', _sets, (v) => setState(() => _sets = v)),
                      const SizedBox(width: 8),
                      _numField('Rep min', _repsMin, (v) => setState(() => _repsMin = v)),
                      const SizedBox(width: 8),
                      _numField('Rep max', _repsMax, (v) => setState(() => _repsMax = v)),
                      const SizedBox(width: 8),
                      _numField('Descanso', _rest, (v) => setState(() => _rest = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedExerciseId == null ? null : _addItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppConstants.neonAccent),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Adicionar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(() => _showAddForm = false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (!_showAddForm)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showAddForm = true),
                    icon: const Icon(Icons.add),
                    label: Text('Adicionar exercício', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.neonAccent),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _numField(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 2),
          TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            onChanged: (v) => onChanged(int.tryParse(v) ?? value),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(AppConstants.primaryDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
