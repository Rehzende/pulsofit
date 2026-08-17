import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _instagramController;
  late TextEditingController _weightController;
  String? _selectedGender;
  DateTime? _birthday;
  bool _isLoading = false;
  bool _isSavingTrainer = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: auth.fullName);
    _phoneController = TextEditingController(text: auth.whatsappNumber);
    _instagramController = TextEditingController(
      text: auth.instagramHandle ?? '',
    );
    _weightController = TextEditingController(
      text: auth.weightKg != null ? auth.weightKg!.toStringAsFixed(0) : '',
    );
    _selectedGender = auth.gender;
    _birthday = auth.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int? _ageFrom(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Selecione sua data de nascimento',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  // ── Save basic profile (same for Student and Trainer) ──────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final Map<String, dynamic> data = {
        'full_name': _nameController.text.trim(),
        'gender': _selectedGender,
      };

      // Only add whatsapp_number for students
      if (!auth.isTrainer) {
        data['whatsapp_number'] = _phoneController.text.trim();
      }

      // Physical data (weight + birthday) — relevant for students/athletes.
      final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
      if (weight != null && weight > 0) {
        data['weight_kg'] = weight;
      }
      if (_birthday != null) {
        data['birthday'] = _birthday!.toIso8601String();
      }

      final success = await auth.updateProfile(data);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil atualizado com sucesso!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Erro ao atualizar perfil'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro inesperado ao salvar perfil')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save trainer profile (instagram_handle via /trainer/profile) ─
  Future<void> _saveTrainerProfile() async {
    final instagram = _instagramController.text.trim();
    // Strip leading @ if user typed it
    final handle = instagram.startsWith('@') ? instagram.substring(1) : instagram;
    if (handle.isEmpty) return;

    setState(() => _isSavingTrainer = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final response = await auth.dio.put(
        '${AppConstants.baseUrl}/trainer/profile',
        data: {'instagram_handle': handle},
      );
      if (response.statusCode == 200) {
        // Refresh user details so instagramHandle getter is updated
        await auth.fetchUserDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('@Instagram salvo com sucesso!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar @Instagram: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTrainer = false);
    }
  }

  // ── Submit — calls both if trainer ────────────────────────────────
  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await _saveProfile();
    if (auth.isTrainer && _instagramController.text.trim().isNotEmpty) {
      await _saveTrainerProfile();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Editar Perfil',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nome completo ───────────────────────────────────
                _buildLabel('Nome Completo'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: _buildInputDecoration('Seu nome'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira seu nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── WhatsApp (estudantes) ──────────────────────────
                if (!auth.isTrainer) ...[
                  _buildLabel('WhatsApp / Telefone'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _buildInputDecoration('(00) 00000-0000'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // ── Peso + Data de nascimento ─────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Peso (kg)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _weightController,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: _buildInputDecoration('Ex: 75'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Nascimento'),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickBirthday,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: _buildInputDecoration('Selecione').copyWith(
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: Color(AppConstants.neonAccent),
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  _birthday != null
                                      ? '${_birthday!.day.toString().padLeft(2, '0')}/${_birthday!.month.toString().padLeft(2, '0')}/${_birthday!.year}'
                                          '${_ageFrom(_birthday) != null ? '  (${_ageFrom(_birthday)} anos)' : ''}'
                                      : 'Selecione',
                                  style: GoogleFonts.inter(
                                    color: _birthday != null ? Colors.white : Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Sexo ────────────────────────────────────────────
                _buildLabel('Sexo'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  dropdownColor: const Color(AppConstants.cardDark),
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: _buildInputDecoration('Selecione'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Feminino')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Outro')),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),

                // ── Instagram (só para Trainer) ─────────────────────
                if (auth.isTrainer) ...[
                  const SizedBox(height: 24),
                  _buildLabel('@Instagram'),
                  const SizedBox(height: 4),
                  Text(
                    'Aparecerá no card de compartilhamento dos seus alunos',
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _instagramController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _buildInputDecoration(
                      '@seu_perfil',
                    ).copyWith(
                      prefixIcon: const Icon(
                        Icons.alternate_email,
                        color: Color(AppConstants.neonAccent),
                        size: 20,
                      ),
                    ),
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                  ),
                ],

                const SizedBox(height: 40),

                // ── Botão salvar ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isSavingTrainer) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.neonAccent),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: (_isLoading || _isSavingTrainer)
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.black),
                          )
                        : Text(
                            'Salvar Alterações',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: const Color(AppConstants.textSecondary),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white24),
      filled: true,
      fillColor: const Color(AppConstants.cardDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(AppConstants.neonAccent)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
