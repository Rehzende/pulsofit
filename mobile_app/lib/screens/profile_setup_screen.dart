import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  DateTime? _birthday;
  String? _gender;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(AppConstants.neonAccent),
            onPrimary: Colors.black,
            surface: Color(AppConstants.cardDark),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _finish() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe seu nome.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final data = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        if (_birthday != null)
          'birthday': _birthday!.toIso8601String(),
        if (_gender != null) 'gender': _gender,
        if (_whatsappCtrl.text.trim().isNotEmpty)
          'whatsapp_number': _whatsappCtrl.text.trim(),
      };
      final ok = await auth.updateProfile(data);
      if (mounted) {
        if (ok) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao salvar perfil. Tente novamente.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Identidade', 'Detalhes'];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(AppConstants.primaryDark),
        appBar: AppBar(
          backgroundColor: const Color(AppConstants.primaryDark),
          foregroundColor: Colors.white,
          title: Text(
            'Complete seu perfil',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
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
              if (_step == 0) Expanded(child: _buildIdentityStep()),
              if (_step == 1) Expanded(child: _buildDetailsStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como podemos te chamar?', style: _titleStyle()),
        Text(
          'Seu nome aparecerá no app e para seu treinador.',
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Ex: João Silva').copyWith(
            labelText: 'Nome completo *',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Data de nascimento',
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppConstants.borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: Colors.grey[500], size: 18),
                const SizedBox(width: 12),
                Text(
                  _birthday != null
                      ? '${_birthday!.day.toString().padLeft(2, '0')}/${_birthday!.month.toString().padLeft(2, '0')}/${_birthday!.year}'
                      : 'Selecionar data (opcional)',
                  style: GoogleFonts.inter(
                    color: _birthday != null ? Colors.white : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _nextButton('Próxima etapa', () {
          if (_nameCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor, informe seu nome.')),
            );
            return;
          }
          setState(() => _step = 1);
        }),
      ],
    );
  }

  Widget _buildDetailsStep() {
    const genders = [
      ('MALE', 'Masculino'),
      ('FEMALE', 'Feminino'),
      ('OTHER', 'Outro'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mais sobre você', style: _titleStyle()),
        Text(
          'Essas informações ajudam a personalizar seus treinos.',
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 24),
        Text(
          'Sexo (opcional)',
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: genders.map(((String, String) g) {
            final selected = _gender == g.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _gender = selected ? null : g.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    g.$2,
                    style: GoogleFonts.inter(
                      color: selected
                          ? const Color(AppConstants.neonAccent)
                          : Colors.grey[300],
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _whatsappCtrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Ex: 11999999999').copyWith(
            labelText: 'WhatsApp (opcional)',
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.neonAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _saving
                ? const CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2)
                : Text(
                    'Concluir',
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
      labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
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
        borderSide: BorderSide(
            color: const Color(AppConstants.neonAccent).withOpacity(0.6)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
