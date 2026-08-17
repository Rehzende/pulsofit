import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class TrainerSetupWizardScreen extends StatefulWidget {
  const TrainerSetupWizardScreen({super.key});

  @override
  State<TrainerSetupWizardScreen> createState() => _TrainerSetupWizardScreenState();
}

class _TrainerSetupWizardScreenState extends State<TrainerSetupWizardScreen> {
  int _step = 0;
  bool _saving = false;

  final _brandCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _gymCtrl = TextEditingController();
  final List<String> _specialties = [];
  final List<String> _gyms = [];
  String? _selectedModality;

  static const _allSpecialties = [
    'Musculacao',
    'Emagrecimento',
    'HIIT',
    'Funcional',
    'Crossfit',
    'Yoga',
    'Pilates',
    'Corrida',
    'Natacao',
    'Reabilitacao',
    'Hipertrofia',
    'Powerlifting',
  ];

  @override
  void dispose() {
    _brandCtrl.dispose();
    _bioCtrl.dispose();
    _rateCtrl.dispose();
    _whatsappCtrl.dispose();
    _gymCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.dio.put('${AppConstants.baseUrl}/trainer/profile', data: {
        'brand_name': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'specialties': _specialties.isEmpty ? null : _specialties,
        'modality': _selectedModality,
        'gyms': _gyms.isEmpty ? null : _gyms,
        'hourly_rate': double.tryParse(_rateCtrl.text.trim()),
        'whatsapp_number': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'is_available_for_hire': true,
      });
      await auth.fetchUserDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil configurado com sucesso!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Marca', 'Especialidades', 'Servicos', 'Contato'];

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryDark),
        foregroundColor: Colors.white,
        title: Text('Configurar Perfil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step progress
            Row(
              children: List.generate(steps.length, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? const Color(AppConstants.neonAccent)
                              : const Color(AppConstants.borderColor),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: GoogleFonts.inter(
                          color: i <= _step
                              ? const Color(AppConstants.neonAccent)
                              : Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ),
            const SizedBox(height: 28),
            if (_step == 0) Expanded(child: _buildBrandStep()),
            if (_step == 1) Expanded(child: _buildSpecialtiesStep()),
            if (_step == 2) Expanded(child: _buildServicesStep()),
            if (_step == 3) Expanded(child: _buildContactStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como se chama sua marca?', style: _titleStyle()),
        Text('Este nome aparece no seu perfil publico.',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _brandCtrl,
          label: 'Nome da marca (ex: Academia do Joao)',
          hint: 'Pode usar seu nome ou criar uma marca',
        ),
        const SizedBox(height: 20),
        Text('Sobre voce', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _bioCtrl,
          maxLines: 4,
          maxLength: 300,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Conte um pouco sobre sua experiencia e metodo de trabalho...'),
        ),
        const Spacer(),
        _nextButton('Proxima etapa', () => setState(() => _step = 1)),
      ],
    );
  }

  Widget _buildSpecialtiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quais sao suas especialidades?', style: _titleStyle()),
        Text('Selecione todas que se aplicam.',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 20),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSpecialties.map((s) {
              final selected = _specialties.contains(s);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _specialties.remove(s) : _specialties.add(s);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(AppConstants.neonAccent).withOpacity(0.15)
                        : const Color(AppConstants.cardDark),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? const Color(AppConstants.neonAccent)
                          : const Color(AppConstants.borderColor),
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      color: selected ? const Color(AppConstants.neonAccent) : Colors.grey[300],
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _nextButton('Proxima etapa', () => setState(() => _step = 2)),
      ],
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configure seus servicos', style: _titleStyle()),
          const SizedBox(height: 24),

          // Modality Selection
          Text('Modalidade de atendimento',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModalityChip('Presencial', 'presencial'),
              _buildModalityChip('Online', 'online'),
              _buildModalityChip('Hibrido', 'hibrido'),
            ],
          ),
          const SizedBox(height: 24),

          // Value
          Text('Valor da consulta/sessao',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _rateCtrl,
            label: 'Valor (R\$)',
            hint: 'Ex: 150',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // Gyms/Locations
          Text('Locais de atendimento (academias/studios)',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ..._gyms.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: e.value),
                    onChanged: (val) => _gyms[e.key] = val,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _inputDecoration('Academia/Studio').copyWith(
                      labelText: 'Local ${e.key + 1}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _gyms.removeAt(e.key)),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          )),
          OutlinedButton.icon(
            onPressed: () => setState(() => _gyms.add('')),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar local'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(AppConstants.neonAccent)),
            ),
          ),
          const SizedBox(height: 24),

          _nextButton('Proxima etapa', () => setState(() => _step = 3)),
        ],
      ),
    );
  }

  Widget _buildModalityChip(String label, String value) {
    final isSelected = _selectedModality == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedModality = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(AppConstants.neonAccent) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(AppConstants.neonAccent) : Colors.grey[600]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.black : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como os alunos entram em contato?', style: _titleStyle()),
        Text('Numero do WhatsApp para receber solicitacoes.',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _whatsappCtrl,
          label: 'WhatsApp (com DDD)',
          hint: 'Ex: 11999999999',
          keyboardType: TextInputType.phone,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.neonAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _saving
                ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                : Text(
                    'Concluir configuracao',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: _inputDecoration(hint).copyWith(labelText: label),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
      labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(AppConstants.cardDark),
      counterStyle: GoogleFonts.inter(color: Colors.grey[600]),
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
        borderSide: BorderSide(color: const Color(AppConstants.neonAccent).withOpacity(0.6)),
      ),
    );
  }

  Widget _nextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.neonAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  TextStyle _titleStyle() => GoogleFonts.inter(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
}
