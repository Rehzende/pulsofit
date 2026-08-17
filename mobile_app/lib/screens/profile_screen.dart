import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/bluetooth_controller.dart';
import '../core/constants.dart';
import 'login_screen.dart';

import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'edit_profile_screen.dart';
import 'anamnesis_screen.dart';
import 'device_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(BuildContext context, String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: image.name),
      });

      // Add type param to URL
      final response = await authProvider.dio.post(
        '${AppConstants.baseUrl}/uploads/logo?type=$type',
        data: formData,
      );

      if (response.statusCode == 200) {
        // Refresh user details to get new URLs
        await authProvider.fetchUserDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload realizado com sucesso!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer upload da imagem')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Perfil',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            // Profile Avatar
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(AppConstants.neonAccent),
                        const Color(AppConstants.neonAccent).withOpacity(0.6),
                      ],
                    ),
                    image: authProvider.getProfileImageUrl() != null
                        ? DecorationImage(
                            image: NetworkImage(authProvider.getProfileImageUrl()!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: authProvider.getProfileImageUrl() == null
                      ? Center(
                          child: Text(
                            (authProvider.fullName != null && authProvider.fullName!.isNotEmpty)
                                ? authProvider.fullName![0].toUpperCase()
                                : (authProvider.userEmail?.substring(0, 1).toUpperCase() ?? 'U'),
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadImage(context, 'avatar'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(AppConstants.neonAccent),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              (authProvider.fullName != null && authProvider.fullName!.isNotEmpty)
                  ? authProvider.fullName!
                  : (authProvider.userEmail?.split('@').first ?? 'User'),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(AppConstants.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              authProvider.userEmail ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(AppConstants.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(AppConstants.neonAccent),
                side: const BorderSide(color: Color(AppConstants.neonAccent)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Editar Perfil',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 32),
            
            // Stats Cards
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(AppConstants.borderColor),
                ),
              ),
              child: Column(
                children: [
                  _buildStatRow('Nível', '${authProvider.level}'),
                  const Divider(height: 32),
                  _buildStatRow('XP Total', '${authProvider.xpPoints}'),
                  const Divider(height: 32),
                  _buildStatRow('Sequência', '${authProvider.currentStreak} dias'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Heart Rate Monitor Section
            Consumer<BluetoothController>(
              builder: (context, bluetooth, child) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.cardDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(AppConstants.borderColor),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monitor Cardíaco',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(
                            Icons.favorite,
                            color: bluetooth.isConnected ? Colors.red : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (bluetooth.isConnected) ...[
                        Text(
                          'Conectado a: ${bluetooth.deviceName}',
                          style: GoogleFonts.inter(color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${bluetooth.heartRate} BPM',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => bluetooth.disconnect(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Desconectar'),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Nenhum dispositivo conectado',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeviceScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bluetooth_searching),
                            label: const Text('Gerenciar dispositivos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(AppConstants.neonAccent),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),

            // Legal & Account
            Container(
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppConstants.borderColor)),
              ),
              child: Column(
                children: [
                  if (!authProvider.isTrainer) ...[
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined, color: Color(AppConstants.neonAccent)),
                      title: Text(
                        'Editar Anamnese',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Objetivo, nível, lesões e condições',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnamnesisScreen(isEditing: true),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: const Color(AppConstants.borderColor)),
                  ],
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                    title: Text(
                      'Política de Privacidade',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, color: const Color(AppConstants.borderColor)),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                    title: Text(
                      'Excluir minha conta',
                      style: GoogleFonts.inter(color: Colors.redAccent),
                    ),
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),

            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Etapa 1 (somente trainers): aviso sobre impacto nos alunos
    if (authProvider.isTrainer) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(AppConstants.cardDark),
          title: Text(
            'Atenção: você é Personal Trainer',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Ao excluir sua conta, todos os seus alunos perderão o vínculo com você. '
            'Os treinos já atribuídos a eles serão mantidos, mas eles não terão mais acesso ao seu perfil de treinador.\n\n'
            'Esta ação não pode ser desfeita.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Entendo, continuar',
                style: GoogleFonts.inter(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    // Etapa 2 (todos): confirmação digitando "EXCLUIR"
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUploading = true);
    try {
      await authProvider.dio.delete('${AppConstants.baseUrl}/users/me');
      await authProvider.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir conta. Tente novamente.')),
      );
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.neonAccent),
          ),
        ),
      ],
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(AppConstants.cardDark),
      title: Text(
        'Confirmar exclusão',
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Todos os seus dados serão excluídos permanentemente e esta ação não pode ser desfeita.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Para confirmar, digite EXCLUIR abaixo:',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'EXCLUIR',
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              filled: true,
              fillColor: const Color(AppConstants.cardElevated),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
            onChanged: (v) => setState(() => _canDelete = v == 'EXCLUIR'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Excluir permanentemente',
            style: GoogleFonts.inter(
              color: _canDelete ? Colors.redAccent : Colors.white24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
