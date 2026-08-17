import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/trainer_service.dart';

class TrainerServiceRegistrationScreen extends StatefulWidget {
  const TrainerServiceRegistrationScreen({super.key});

  @override
  State<TrainerServiceRegistrationScreen> createState() => _TrainerServiceRegistrationScreenState();
}

class _TrainerServiceRegistrationScreenState extends State<TrainerServiceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _gymsController = TextEditingController();

  bool _isLoading = false;
  bool _isAvailableForHire = false;
  List<String> _specialties = [];
  List<String> _gyms = [];
  String? _modality;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      final profile = await trainerService.getProfile();
      
      if (profile != null) {
        setState(() {
          _bioController.text = profile.bio ?? '';
          _specialties = profile.specialties ?? [];
          _gyms = profile.gyms ?? [];
          _hourlyRateController.text = profile.hourlyRate?.toString() ?? '';
          _whatsappController.text = profile.whatsappNumber ?? '';
          _isAvailableForHire = profile.isAvailableForHire;
          _modality = profile.modality;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSpecialty(String value) {
    if (value.isNotEmpty && !_specialties.contains(value)) {
      setState(() {
        _specialties.add(value);
        _specialtiesController.clear();
      });
    }
  }

  void _removeSpecialty(String value) {
    setState(() {
      _specialties.remove(value);
    });
  }

  void _addGym(String value) {
    if (value.isNotEmpty && !_gyms.contains(value)) {
      setState(() {
        _gyms.add(value);
        _gymsController.clear();
      });
    }
  }

  void _removeGym(String value) {
    setState(() {
      _gyms.remove(value);
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _specialtiesController.dispose();
    _hourlyRateController.dispose();
    _whatsappController.dispose();
    _gymsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      
      await trainerService.updateProfile(
        bio: _bioController.text,
        specialties: _specialties,
        gyms: _gyms,
        modality: _modality,
        hourlyRate: double.tryParse(_hourlyRateController.text),
        whatsappNumber: _whatsappController.text,
        isAvailableForHire: _isAvailableForHire,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Registrar Serviços',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Availability Switch
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.cardDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isAvailableForHire 
                              ? const Color(AppConstants.neonAccent) 
                              : const Color(AppConstants.borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Disponível para Contratação',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Seus serviços aparecerão na lista de treinadores.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAvailableForHire,
                            onChanged: (value) {
                              setState(() => _isAvailableForHire = value);
                            },
                            activeColor: const Color(AppConstants.neonAccent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Modality Selection
                    Text(
                      'Modalidade de Atendimento',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['presencial', 'online', 'hibrido'].map((mode) {
                        return FilterChip(
                          label: Text(
                            mode == 'presencial'
                              ? 'Presencial'
                              : mode == 'online'
                              ? 'Online'
                              : 'Híbrido',
                          ),
                          selected: _modality == mode,
                          onSelected: (selected) {
                            setState(() {
                              _modality = selected ? mode : null;
                            });
                          },
                          backgroundColor: const Color(AppConstants.cardDark),
                          side: BorderSide(
                            color: _modality == mode
                                ? const Color(AppConstants.neonAccent)
                                : const Color(AppConstants.borderColor),
                          ),
                          selectedColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.2),
                          labelStyle: GoogleFonts.inter(
                            color: _modality == mode
                                ? const Color(AppConstants.neonAccent)
                                : Colors.grey,
                            fontWeight: _modality == mode ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Informações Profissionais',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Bio
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Biografia',
                        labelStyle: GoogleFonts.inter(color: Colors.grey),
                        hintText: 'Conte um pouco sobre sua experiência...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(AppConstants.cardDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Specialties
                    TextFormField(
                      controller: _specialtiesController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Especialidades',
                        labelStyle: GoogleFonts.inter(color: Colors.grey),
                        hintText: 'Ex: Musculação, Yoga (pressione Enter)',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(AppConstants.cardDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, color: Color(AppConstants.neonAccent)),
                          onPressed: () => _addSpecialty(_specialtiesController.text),
                        ),
                      ),
                      onFieldSubmitted: _addSpecialty,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specialties.map((s) => Chip(
                        label: Text(s),
                        backgroundColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(color: const Color(AppConstants.neonAccent)),
                        deleteIcon: const Icon(Icons.close, size: 18, color: Color(AppConstants.neonAccent)),
                        onDeleted: () => _removeSpecialty(s),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(AppConstants.neonAccent)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Gyms/Academias
                    TextFormField(
                      controller: _gymsController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Academias / Locais de Atendimento',
                        labelStyle: GoogleFonts.inter(color: Colors.grey),
                        hintText: 'Ex: Academia X, Estúdio Y (pressione Enter)',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(AppConstants.cardDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, color: Color(AppConstants.neonAccent)),
                          onPressed: () => _addGym(_gymsController.text),
                        ),
                      ),
                      onFieldSubmitted: _addGym,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _gyms.map((g) => Chip(
                        label: Text(g),
                        backgroundColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(color: const Color(AppConstants.neonAccent)),
                        deleteIcon: const Icon(Icons.close, size: 18, color: Color(AppConstants.neonAccent)),
                        onDeleted: () => _removeGym(g),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(AppConstants.neonAccent)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Hourly Rate
                    TextFormField(
                      controller: _hourlyRateController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Valor Hora (R\$)',
                        labelStyle: GoogleFonts.inter(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(AppConstants.cardDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Digite um valor válido';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp
                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'WhatsApp para Contato',
                        labelStyle: GoogleFonts.inter(color: Colors.grey),
                        hintText: 'Ex: 5511999999999',
                        filled: true,
                        fillColor: const Color(AppConstants.cardDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppConstants.neonAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Salvar Alterações',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
