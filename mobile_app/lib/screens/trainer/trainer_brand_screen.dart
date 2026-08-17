import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants.dart';

// ──────────────────────────────────────────────────────────────────────────────
// PULSO Trainer Brand Screen — Fase 2 Paridade Mobile × Web
// Matches the web settings portal: Branding, Marketplace, Link Público
// ──────────────────────────────────────────────────────────────────────────────

class TrainerBrandScreen extends StatefulWidget {
  const TrainerBrandScreen({super.key});

  @override
  State<TrainerBrandScreen> createState() => _TrainerBrandScreenState();
}

class _TrainerBrandScreenState extends State<TrainerBrandScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _brandNameController;
  late TextEditingController _slugController;
  late TextEditingController _instagramController;

  // State
  String _primaryColor = '#7C3AED';
  bool _isAvailableForHire = false;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isLoading = true;
  String? _slugError;

  // Preset color palette (mirrors web portal)
  static const List<String> _palette = [
    '#ef4444', '#f97316', '#f59e0b', '#84cc16',
    '#10b981', '#06b6d4', '#3b82f6', '#8b5cf6',
    '#d946ef', '#f43f5e',
  ];

  @override
  void initState() {
    super.initState();
    _brandNameController = TextEditingController();
    _slugController = TextEditingController();
    _instagramController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _slugController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await auth.dio.get('${AppConstants.baseUrl}/trainer/profile');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _brandNameController.text = data['brand_name'] ?? '';
          _slugController.text = data['slug'] ?? '';
          _instagramController.text = data['instagram_handle'] ?? '';
          _primaryColor = data['primary_color'] ?? '#7C3AED';
          _isAvailableForHire = data['is_available_for_hire'] ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback to AuthProvider cached values
      setState(() {
        _instagramController.text = auth.instagramHandle ?? '';
        _isLoading = false;
      });
    }
  }

  // ── Upload Logo ─────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: image.name),
      });
      final response = await auth.dio.post(
        '${AppConstants.baseUrl}/uploads/logo?type=logo',
        data: formData,
      );
      if (response.statusCode == 200) {
        await auth.fetchUserDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo atualizada com sucesso! ✅')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Save Brand Settings ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_slugError != null) return;

    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final slug = _slugController.text.trim();
      final instagram = _instagramController.text.trim().replaceAll('@', '');

      await auth.dio.put(
        '${AppConstants.baseUrl}/trainer/profile',
        data: {
          'brand_name': _brandNameController.text.trim(),
          if (slug.isNotEmpty) 'slug': slug,
          'primary_color': _primaryColor,
          'is_available_for_hire': _isAvailableForHire,
          if (instagram.isNotEmpty) 'instagram_handle': instagram,
        },
      );

      // Also update auth cache
      await auth.fetchUserDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações de marca salvas! 🎉')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('slug')) {
          setState(() => _slugError = 'Este link já está em uso. Escolha outro.');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Toggle Marketplace ──────────────────────────────────────────────────────
  Future<void> _toggleMarketplace(bool value) async {
    setState(() => _isAvailableForHire = value);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.dio.put(
        '${AppConstants.baseUrl}/trainer/profile',
        data: {'is_available_for_hire': value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Você agora aparece no marketplace! 🚀'
                  : 'Perfil ocultado do marketplace.',
            ),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() => _isAvailableForHire = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar status')),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(AppConstants.neonAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Configurações de Marca',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || _isLoading) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Salvar',
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.neonAccent),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(AppConstants.neonAccent)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LOGO SECTION ─────────────────────────────────────
                    _buildSectionLabel('Logo da Marca'),
                    const SizedBox(height: 12),
                    _buildLogoCard(auth),

                    const SizedBox(height: 28),

                    // ── IDENTITY SECTION ──────────────────────────────────
                    _buildSectionLabel('Identidade'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        children: [
                          // Brand name
                          _buildField(
                            label: 'Nome da Marca',
                            icon: Icons.business_outlined,
                            child: TextFormField(
                              controller: _brandNameController,
                              style: GoogleFonts.inter(
                                  color: const Color(AppConstants.textPrimary)),
                              decoration: _inputDec('Sua Consultoria'),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Insira o nome da sua marca';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Instagram
                          _buildField(
                            label: '@Instagram',
                            icon: Icons.alternate_email,
                            child: TextFormField(
                              controller: _instagramController,
                              style: GoogleFonts.inter(
                                  color: const Color(AppConstants.textPrimary)),
                              decoration: _inputDec('@seu_perfil'),
                              autocorrect: false,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── LINK PÚBLICO (SLUG) ───────────────────────────────
                    _buildSectionLabel('Sua Página Pública'),
                    const SizedBox(height: 4),
                    Text(
                      'Compartilhe no Instagram para atrair novos alunos',
                      style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Slug input with prefix
                          Text(
                            'Link Público (Slug)',
                            style: GoogleFonts.inter(
                              color: const Color(AppConstants.textSecondary),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.primaryDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _slugError != null
                                    ? Colors.redAccent
                                    : const Color(AppConstants.borderColor),
                              ),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  child: Text(
                                    'pulsofit.app/t/',
                                    style: GoogleFonts.inter(
                                      color: const Color(AppConstants.textSecondary),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 20,
                                    color: const Color(AppConstants.borderColor)),
                                Expanded(
                                  child: TextFormField(
                                    controller: _slugController,
                                    style: GoogleFonts.inter(
                                      color: const Color(AppConstants.textPrimary),
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'seu-nome',
                                      hintStyle: GoogleFonts.inter(
                                          color: Colors.white24, fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-z0-9\-]')),
                                    ],
                                    onChanged: (v) {
                                      if (v.isEmpty) {
                                        setState(() => _slugError = null);
                                        return;
                                      }
                                      final valid = RegExp(
                                              r'^[a-z0-9][a-z0-9\-]{1,28}[a-z0-9]$')
                                          .hasMatch(v);
                                      setState(() {
                                        _slugError = valid
                                            ? null
                                            : 'Use apenas letras minúsculas, números e hífens (3-30 chars)';
                                      });
                                    },
                                  ),
                                ),
                                // Copy button
                                if (_slugController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.copy_outlined,
                                        size: 18,
                                        color: Color(AppConstants.neonAccent)),
                                    onPressed: () {
                                      final slug = _slugController.text.trim();
                                      Clipboard.setData(
                                        ClipboardData(
                                            text: 'https://pulsofit.app/t/$slug'),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Link copiado!')),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (_slugError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _slugError!,
                                style: GoogleFonts.inter(
                                    color: Colors.redAccent, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── COR PRINCIPAL ─────────────────────────────────────
                    _buildSectionLabel('Cor Principal'),
                    const SizedBox(height: 4),
                    Text(
                      'Usada no seu card de compartilhamento e página pública',
                      style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(child: _buildColorPicker()),

                    const SizedBox(height: 28),

                    // ── MARKETPLACE ───────────────────────────────────────
                    _buildSectionLabel('Marketplace'),
                    const SizedBox(height: 12),
                    _buildMarketplaceToggle(),

                    const SizedBox(height: 40),

                    // ── SAVE BUTTON ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isLoading) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppConstants.neonAccent),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(color: Colors.white),
                              )
                            : Text(
                                'Salvar Configurações',
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
    );
  }

  // ── Logo Card ───────────────────────────────────────────────────────────────
  Widget _buildLogoCard(AuthProvider auth) {
    final logoUrl = auth.getTrainerLogoUrl();

    return _buildCard(
      child: Row(
        children: [
          // Logo preview
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadLogo,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.primaryDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(AppConstants.neonAccent)
                          .withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _logoPlaceholder(),
                          ),
                        )
                      : _logoPlaceholder(),
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(AppConstants.neonAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Camera badge
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.neonAccent),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(AppConstants.primaryDark), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logo da Marca',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aparece na sua página pública e no card de compartilhamento',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recomendado: 512×512px (PNG)',
                  style: GoogleFonts.inter(
                      color: const Color(AppConstants.textMuted), fontSize: 11),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadLogo,
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: Text(
                    _isUploading ? 'Enviando…' : 'Alterar Logo',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(AppConstants.neonAccent),
                    side: const BorderSide(color: Color(AppConstants.neonAccent)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Center(
      child: Icon(
        Icons.business_outlined,
        color: const Color(AppConstants.neonAccent).withValues(alpha: 0.4),
        size: 32,
      ),
    );
  }

  // ── Color Picker ────────────────────────────────────────────────────────────
  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected color preview
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hexToColor(_primaryColor),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _hexToColor(_primaryColor).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _primaryColor.toUpperCase(),
              style: GoogleFonts.robotoMono(
                color: const Color(AppConstants.textSecondary),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Palette
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._palette.map((hex) {
              final isSelected = _primaryColor.toLowerCase() == hex.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _primaryColor = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  _hexToColor(hex).withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Marketplace Toggle ──────────────────────────────────────────────────────
  Widget _buildMarketplaceToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAvailableForHire
            ? const Color(AppConstants.neonAccent).withValues(alpha: 0.08)
            : const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAvailableForHire
              ? const Color(AppConstants.neonAccent).withValues(alpha: 0.3)
              : const Color(AppConstants.borderColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAvailableForHire
                          ? Icons.store_rounded
                          : Icons.store_outlined,
                      color: _isAvailableForHire
                          ? const Color(AppConstants.neonAccent)
                          : const Color(AppConstants.textSecondary),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAvailableForHire
                          ? 'Visível no Marketplace'
                          : 'Perfil Privado',
                      style: GoogleFonts.inter(
                        color: _isAvailableForHire
                            ? const Color(AppConstants.textPrimary)
                            : const Color(AppConstants.textSecondary),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Quando ativado, seu perfil será recomendado para alunos que buscam um personal trainer na plataforma Pulso.',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Custom Toggle
          GestureDetector(
            onTap: () => _toggleMarketplace(!_isAvailableForHire),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: _isAvailableForHire
                    ? const Color(AppConstants.neonAccent)
                    : const Color(AppConstants.borderColor),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: _isAvailableForHire
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Layout Helpers ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(AppConstants.textSecondary),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: child,
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(AppConstants.textSecondary)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white24),
      filled: true,
      fillColor: const Color(AppConstants.primaryDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(AppConstants.borderColor)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(AppConstants.borderColor)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(AppConstants.neonAccent)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
