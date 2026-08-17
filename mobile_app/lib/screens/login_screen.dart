import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import 'main_navigation_screen.dart';
import 'anamnesis_screen.dart';

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    return next.copyWith(text: next.text.toUpperCase());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();

  int _step = 0; // 0 = role selection, 1 = email, 2 = token
  String _selectedRole = 'STUDENT';

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // ── Step 1: Request Magic Link ───────────────────────
  Future<void> _handleRequestMagicLink() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.requestMagicLink(_emailController.text.trim(), _selectedRole);

      if (mounted && authProvider.errorMessage != null) {
        _showError(authProvider.errorMessage!);
      }
    }
  }

  // ── Google Sign-In ───────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle(_selectedRole);

    if (success && mounted) {
      if (!authProvider.anamnesisCompleted && !authProvider.anamnesisSkipped) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnamnesisScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else if (mounted && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
    }
  }

  // ── Step 2: Verify Token ─────────────────────────────
  Future<void> _handleVerifyToken() async {
    final token = _tokenController.text.trim().toUpperCase();
    if (token.length < 6) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyMagicLink(token);

    if (success && mounted) {
      if (!authProvider.anamnesisCompleted && !authProvider.anamnesisSkipped) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnamnesisScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else if (mounted && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(AppConstants.errorColor), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(AppConstants.cardElevated),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(AppConstants.errorColor), width: 1),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      body: Stack(
        children: [
          // ========================
          // Ambient Background Blobs
          // ========================
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(AppConstants.neonAccent).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(AppConstants.cyanAccent).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ========================
          // Main Content
          // ========================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (_step == 0) {
                      return _buildRoleSelectionView();
                    } else if (authProvider.magicLinkSent) {
                      return _buildVerifyView(authProvider);
                    } else {
                      return _buildEmailView(authProvider);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VIEW 1: Email Input (Request Magic Link)
  // ══════════════════════════════════════════════════════
  Widget _buildEmailView(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          FadeInDown(
            duration: const Duration(milliseconds: 700),
            child: Column(
              children: [
                // Icon with Glow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(AppConstants.neonAccent),
                        Color(0xFFA855F7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(AppConstants.neonAccent).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Brand Name
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'PULSO',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: const Color(AppConstants.textPrimary),
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: const Color(AppConstants.neonAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Performance Inteligente',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(AppConstants.textSecondary),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 56),

          // Email Field
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-mail',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'seu@email.com',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(AppConstants.textMuted),
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 20,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Por favor, insira um e-mail válido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Magic Link Button
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 300),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(AppConstants.neonAccent).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleRequestMagicLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.neonAccent),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(AppConstants.neonAccent).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Enviar Link Mágico',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Subtitle
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 350),
            child: Text(
              'Sem senha! Enviaremos um link mágico\npara o seu e-mail.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(AppConstants.textMuted),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 400),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: const Color(AppConstants.textMuted).withValues(alpha: 0.3),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(AppConstants.textMuted),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: const Color(AppConstants.textMuted).withValues(alpha: 0.3),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Google Sign-In Button
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 450),
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(AppConstants.textPrimary),
                  side: BorderSide(
                    color: const Color(AppConstants.textMuted).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: const Color(AppConstants.cardElevated),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Entrar com Google',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(AppConstants.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VIEW 2: Token Verification (Check your email)
  // ══════════════════════════════════════════════════════
  Widget _buildVerifyView(AuthProvider authProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Icon
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
                  Icons.mark_email_read_outlined,
                  size: 36,
                  color: Color(AppConstants.successColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verifique seu e-mail',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(AppConstants.textPrimary),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(AppConstants.textSecondary),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Enviamos um link mágico para\n'),
                    TextSpan(
                      text: authProvider.pendingEmail ?? '',
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.neonAccent),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Code Input
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite o código de 6 letras do e-mail:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(AppConstants.textPrimary),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tokenController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  _UpperCaseFormatter(),
                ],
                style: GoogleFonts.firaCode(
                  color: const Color(AppConstants.neonAccent),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '······',
                  hintStyle: GoogleFonts.firaCode(
                    color: const Color(AppConstants.textMuted),
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                  prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Verify Button
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: authProvider.isLoading ? null : _handleVerifyToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(AppConstants.neonAccent).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: authProvider.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verificar e Entrar',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Resend Link
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 350),
          child: TextButton(
            onPressed: authProvider.isLoading
                ? null
                : () async {
                    if (authProvider.pendingEmail != null) {
                      await authProvider.requestMagicLink(authProvider.pendingEmail!, _selectedRole);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Color(AppConstants.successColor), size: 18),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Novo link enviado!')),
                              ],
                            ),
                            backgroundColor: const Color(AppConstants.cardElevated),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Color(AppConstants.successColor), width: 1),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    }
                  },
            child: Text(
              'Reenviar link mágico',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.neonAccent),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Back to email
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 400),
          child: TextButton(
            onPressed: () {
              authProvider.resetMagicLink();
            },
            child: Text(
              'Usar outro e-mail',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 13,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // VIEW 0: Role Selection
  // ══════════════════════════════════════════════════════
  Widget _buildRoleSelectionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo
        FadeInDown(
          duration: const Duration(milliseconds: 700),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(AppConstants.neonAccent),
                      Color(0xFFA855F7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(AppConstants.neonAccent).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'PULSO',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(AppConstants.textPrimary),
                        letterSpacing: -1,
                      ),
                    ),
                    TextSpan(
                      text: '.',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(AppConstants.neonAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Performance Inteligente',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(AppConstants.textSecondary),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 56),

        // Title
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 200),
          child: Text(
            'Como você quer começar?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(AppConstants.textPrimary),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
          child: Text(
            'Escolha seu tipo de conta',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(AppConstants.textSecondary),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),

        // Student Button
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 400),
          child: _buildRoleButton(
            label: 'Sou Aluno',
            description: 'Procurando um personal trainer',
            icon: Icons.school_rounded,
            isSelected: _selectedRole == 'STUDENT',
            onTap: () => setState(() => _selectedRole = 'STUDENT'),
            key: const ValueKey('student_role_button'),
          ),
        ),
        const SizedBox(height: 16),

        // Trainer Button
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 500),
          child: _buildRoleButton(
            label: 'Sou Personal Trainer',
            description: 'Quero oferecer meus serviços',
            icon: Icons.person_4_rounded,
            isSelected: _selectedRole == 'TRAINER',
            onTap: () => setState(() => _selectedRole = 'TRAINER'),
            key: const ValueKey('trainer_role_button'),
          ),
        ),
        const SizedBox(height: 48),

        // Continue Button
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 600),
          child: Container(
            key: const ValueKey('continue_button_container'),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              key: const ValueKey('continue_button'),
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Continuar',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleButton({
    required String label,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(AppConstants.neonAccent)
                : const Color(AppConstants.borderColor),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(AppConstants.neonAccent).withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(AppConstants.neonAccent).withValues(alpha: 0.2)
                    : const Color(AppConstants.cardDark),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(AppConstants.neonAccent)
                    : const Color(AppConstants.textSecondary),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConstants.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConstants.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(AppConstants.neonAccent),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.black,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
