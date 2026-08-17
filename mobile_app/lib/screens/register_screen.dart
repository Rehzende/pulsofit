import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import 'login_screen.dart';

/// Legacy invite registration screen.
/// When a user arrives via invite deep link, this screen shows the
/// invite details and redirects them to the Magic Link login flow.
class RegisterScreen extends StatefulWidget {
  final String? inviteToken;
  
  const RegisterScreen({
    super.key, 
    this.inviteToken,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String? _inviteEmail;
  String? _trainerName;
  bool _isLoadingInvite = true;

  @override
  void initState() {
    super.initState();
    if (widget.inviteToken != null) {
      _fetchInviteDetails();
    } else {
      setState(() => _isLoadingInvite = false);
    }
  }

  Future<void> _fetchInviteDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviteData = await authProvider.getInviteDetails(widget.inviteToken!);

    if (mounted) {
      setState(() {
        _isLoadingInvite = false;
        if (inviteData != null) {
          _inviteEmail = inviteData['email'];
          _trainerName = inviteData['trainer_name'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Convite inválido ou expirado'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoadingInvite
              ? const CircularProgressIndicator(
                  color: Color(AppConstants.neonAccent),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(AppConstants.successColor).withValues(alpha: 0.3),
                                    const Color(AppConstants.successColor).withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(AppConstants.successColor).withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.celebration_rounded,
                                size: 36,
                                color: Color(AppConstants.successColor),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Você foi convidado!',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(AppConstants.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_trainerName != null) ...[
                              Text(
                                'O treinador $_trainerName te convidou para o PULSO.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(AppConstants.textSecondary),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_inviteEmail != null)
                              Text(
                                'Faça login com o e-mail: $_inviteEmail',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(AppConstants.neonAccent),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 300),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(AppConstants.neonAccent),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Continuar para Login',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
}
