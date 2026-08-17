import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  Map<String, dynamic>? _policy;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final response = await Dio().get('${AppConstants.baseUrl}/public/policy');
      if (mounted) {
        setState(() {
          _policy = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar a política de privacidade.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Política de Privacidade',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sections = (_policy?['sections'] as List<dynamic>?) ?? [];
    final lastUpdated = _policy?['last_updated'] ?? '';
    final contact = _policy?['contact_email'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          _policy?['app_name'] ?? 'Pulso',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Última atualização: $lastUpdated',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Contato: $contact',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(AppConstants.neonAccent),
          ),
        ),
        const SizedBox(height: 24),
        ...sections.map((section) {
          final s = section as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppConstants.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['title'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppConstants.neonAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['content'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(AppConstants.textSecondary),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
