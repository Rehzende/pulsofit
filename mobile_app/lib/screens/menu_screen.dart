import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/app_info_service.dart';
import 'profile_screen.dart';
import 'device_screen.dart';
import 'login_screen.dart';
import 'trainer_review_screen.dart';
import 'assessments_screen.dart';
import 'trainer_service_registration_screen.dart';
import 'trainer/trainer_brand_screen.dart';
import 'chat_list_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _appVersion = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await AppInfoService.getFullVersion();
    if (mounted) {
      setState(() => _appVersion = version);
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
          'Menu',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Perfil',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            context,
            icon: Icons.message_outlined,
            title: 'Mensagens',
            subtitle: 'Converse com seu treinador',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            context,
            icon: Icons.bluetooth,
            title: 'Dispositivos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeviceScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            context,
            icon: Icons.assessment_outlined,
            title: 'Avaliações Corporais',
            subtitle: 'Fotos e métricas de progresso',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AssessmentsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          if (!authProvider.isTrainer && authProvider.hasTrainer) ...[

            _buildMenuItem(
              context,
              icon: Icons.star_outline,
              title: 'Avaliar Treinador',
              subtitle: 'Deixe um depoimento para seu coach',
              onTap: () {
                // Find trainer ID from authProvider
                // The authProvider needs to expose the trainer ID.
                // Assuming it's available or we can get it.
                final trainerId = authProvider.trainerId; 
                if (trainerId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainerReviewScreen(
                        trainerId: trainerId,
                        trainerName: authProvider.trainerBrandName ?? 'Seu Treinador',
                      ),
                    ),
                  );
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID do treinador não encontrado.')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            ],
            if (authProvider.isTrainer) ...[

            _buildMenuItem(
              context,
              icon: Icons.palette_outlined,
              title: 'Configurações de Marca',
              subtitle: 'Logo, cores, marketplace e link público',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TrainerBrandScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.work_outline,
              title: 'Meus Serviços',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrainerServiceRegistrationScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              context,
              icon: Icons.credit_card_outlined,
              title: 'Minha Assinatura',
              onTap: () => _showSubscriptionInfo(context, authProvider),
            ),
            const SizedBox(height: 16),
          ],
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Sair',
            isDestructive: true,
            onTap: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 32),
          // App Version
          Center(
            child: Column(
              children: [
                Text(
                  'PULSO',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.neonAccent),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versão $_appVersion',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(AppConstants.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionInfo(BuildContext context, AuthProvider authProvider) {
    final status = authProvider.subscriptionStatus;
    final planName = authProvider.subscriptionPlanName;

    Color statusColor;
    String statusLabel;
    if (status == 'ACTIVE') {
      statusColor = const Color(0xFF22C55E);
      statusLabel = 'Ativo';
    } else if (status == 'TRIAL') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Trial';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusLabel = status != null ? 'Inativo' : 'Sem plano';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(AppConstants.borderColor),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.credit_card_outlined,
                  color: Color(AppConstants.neonAccent),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Minha Assinatura',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppConstants.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plano',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(AppConstants.textSecondary),
                        ),
                      ),
                      Text(
                        planName ?? 'Não definido',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(AppConstants.textSecondary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(AppConstants.neonAccentLight),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Para alterar seu plano de assinatura, acesse o portal web do Pulso em pulsofit.app.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(AppConstants.neonAccentLight),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: const Color(AppConstants.cardDark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(AppConstants.borderColor),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : const Color(AppConstants.neonAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(AppConstants.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
