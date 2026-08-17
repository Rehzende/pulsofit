import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../screens/main_navigation_screen.dart';

class AnamnesisScreen extends StatefulWidget {
  /// When true, the screen is opened from the profile to re-edit an existing
  /// anamnesis: fields are pre-filled and saving pops back instead of going to
  /// the main navigation (onboarding flow).
  final bool isEditing;

  const AnamnesisScreen({super.key, this.isEditing = false});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiService _apiService;
  int _currentStep = 0;
  bool _isLoading = false;
  bool _prefilled = false;

  // ─── Step 1: Dados Básicos ───────────────────────────────
  String _gender = 'MALE';
  String _weight = '';
  String _height = '';
  DateTime? _birthday;

  // ─── Step 2: Objetivos e Perfil ──────────────────────────
  String _primaryGoal = 'Hipertrofia';
  String _experienceLevel = 'Iniciante';
  String _weeklyFrequency = '3x por semana';
  String _sessionDuration = '60 minutos';

  // ─── Step 3: Equipamentos e Ambiente ─────────────────────
  String _equipment = 'Academia completa';

  // ─── Step 4: Saúde e Restrições ──────────────────────────
  String _activityLevel = 'Moderadamente Ativo';
  String _injuries = '';
  String _medicalConditions = '';

  // ─── Options ─────────────────────────────────────────────
  final _goals = ['Hipertrofia', 'Emagrecimento', 'Condicionamento', 'Força', 'Saúde Geral', 'Reabilitação'];
  final _levels = ['Iniciante', 'Intermediário', 'Avançado'];
  final _frequencies = ['2x por semana', '3x por semana', '4x por semana', '5x por semana', '6x ou mais'];
  final _durations = ['30 minutos', '45 minutos', '60 minutos', '90 minutos', '2 horas ou mais'];
  final _equipmentOptions = [
    'Academia completa',
    'Halteres em casa',
    'Elásticos / bandas',
    'Sem equipamento (peso corporal)',
    'Fisioterapia / reabilitação',
  ];
  final _activityLevels = ['Sedentário', 'Levemente Ativo', 'Moderadamente Ativo', 'Muito Ativo', 'Extremamente Ativo'];
  final _genders = [
    {'label': 'Masculino', 'value': 'MALE'},
    {'label': 'Feminino', 'value': 'FEMALE'},
    {'label': 'Outro', 'value': 'OTHER'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(auth.dio);

    // Re-edit mode: pre-fill from the user's saved data.
    if (widget.isEditing && !_prefilled) {
      _prefilled = true;
      if (auth.gender != null && _genders.any((g) => g['value'] == auth.gender)) {
        _gender = auth.gender!;
      }
      if (auth.weightKg != null) _weight = auth.weightKg!.toStringAsFixed(0);

      final mh = auth.medicalHistory;
      if (mh != null) {
        String pick(String key, List<String> opts, String fallback) {
          final v = mh[key]?.toString();
          return (v != null && opts.contains(v)) ? v : fallback;
        }

        _primaryGoal = pick('goal', _goals, _primaryGoal);
        _experienceLevel = pick('experience_level', _levels, _experienceLevel);
        _weeklyFrequency = pick('weekly_frequency', _frequencies, _weeklyFrequency);
        _sessionDuration = pick('session_duration', _durations, _sessionDuration);
        _equipment = pick('equipment', _equipmentOptions, _equipment);
        _activityLevel = pick('activity_level', _activityLevels, _activityLevel);
        _injuries = mh['injuries']?.toString() ?? '';
        _medicalConditions = mh['medical_conditions']?.toString() ?? '';
      }
    }
  }

  Future<void> _submit(bool skipped) async {
    if (!skipped && !_formKey.currentState!.validate()) return;
    _formKey.currentState?.save();

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (!skipped) {
        final medicalHistory = {
          'goal': _primaryGoal,
          'experience_level': _experienceLevel,
          'weekly_frequency': _weeklyFrequency,
          'session_duration': _sessionDuration,
          'equipment': _equipment,
          'activity_level': _activityLevel,
          'injuries': _injuries,
          'medical_conditions': _medicalConditions,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        final updateData = {
          'medical_history': medicalHistory,
          'anamnesis_completed': true,
          'gender': _gender,
          'weight_kg': double.tryParse(_weight),
        };

        await _apiService.updateProfile(updateData);
        auth.completeAnamnesis();
        await auth.fetchUserDetails(); // refresh cached medical_history/weight
      } else {
        auth.skipAnamnesis();
      }

      if (!mounted) return;

      if (widget.isEditing) {
        // Re-edit flow: just go back to the profile.
        if (!skipped) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anamnese atualizada!')),
          );
        }
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Steps ───────────────────────────────────────────────
  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Dados Básicos'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: _buildStep1(),
      ),
      Step(
        title: const Text('Objetivos'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: _buildStep2(),
      ),
      Step(
        title: const Text('Ambiente'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: _buildStep3(),
      ),
      Step(
        title: const Text('Saúde'),
        isActive: _currentStep >= 3,
        state: StepState.indexed,
        content: _buildStep4(),
      ),
    ];
  }

  Widget _buildStep1() => Column(
        children: [
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gênero'),
            items: _genders
                .map((g) => DropdownMenuItem(value: g['value'], child: Text(g['label']!)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _weight,
            decoration: const InputDecoration(
              labelText: 'Peso (kg)',
              hintText: 'Ex: 75.5',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe seu peso';
              if (double.tryParse(v) == null) return 'Peso inválido';
              return null;
            },
            onChanged: (v) => _weight = v,
            onSaved: (v) => _weight = v ?? '',
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Altura (cm)',
              hintText: 'Ex: 175',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _height = v,
            onSaved: (v) => _height = v ?? '',
          ),
        ],
      );

  Widget _buildStep2() => Column(
        children: [
          DropdownButtonFormField<String>(
            value: _primaryGoal,
            decoration: const InputDecoration(labelText: 'Objetivo Principal'),
            items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _primaryGoal = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _experienceLevel,
            decoration: const InputDecoration(labelText: 'Nível de Experiência'),
            items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _experienceLevel = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _weeklyFrequency,
            decoration: const InputDecoration(labelText: 'Frequência Semanal'),
            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _weeklyFrequency = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _sessionDuration,
            decoration: const InputDecoration(labelText: 'Duração por Sessão'),
            items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _sessionDuration = v!),
          ),
        ],
      );

  Widget _buildStep3() => Column(
        children: [
          DropdownButtonFormField<String>(
            value: _equipment,
            decoration:
                const InputDecoration(labelText: 'Equipamentos disponíveis'),
            items: _equipmentOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _equipment = v!),
          ),
        ],
      );

  Widget _buildStep4() => Column(
        children: [
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(labelText: 'Nível de Atividade Atual'),
            items: _activityLevels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => _activityLevel = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _injuries,
            decoration: const InputDecoration(
              labelText: 'Lesões ou restrições físicas',
              hintText: 'Ex: Dor no joelho direito, hérnia de disco...',
            ),
            maxLines: 3,
            onChanged: (v) => _injuries = v,
            onSaved: (v) => _injuries = v ?? '',
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _medicalConditions,
            decoration: const InputDecoration(
              labelText: 'Condições médicas relevantes',
              hintText: 'Ex: Hipertensão, diabetes, cardiopatia...',
            ),
            maxLines: 2,
            onChanged: (v) => _medicalConditions = v,
            onSaved: (v) => _medicalConditions = v ?? '',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estas informações são usadas para personalizar seu treino. Casos graves devem ser avaliados por um médico antes de iniciar atividade física.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[300],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Anamnese' : 'Anamnese'),
        automaticallyImplyLeading: widget.isEditing,
        actions: widget.isEditing
            ? null
            : [
                TextButton(
                  onPressed: _isLoading ? null : () => _submit(true),
                  child: Text(
                    'Pular',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (s) => setState(() => _currentStep = s),
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
            } else {
              _submit(false);
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            final isLast = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading && isLast
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(isLast ? 'Salvar e Continuar' : 'Próximo',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Voltar'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: _buildSteps(),
        ),
      ),
    );
  }
}
