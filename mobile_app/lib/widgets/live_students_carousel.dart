import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/live_session.dart';
import '../services/trainer_service.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_detail_screen.dart';
import '../core/constants.dart';

class LiveStudentsCarousel extends StatefulWidget {
  final List<LiveSession> liveSessions;

  const LiveStudentsCarousel({
    super.key,
    required this.liveSessions,
  });

  @override
  State<LiveStudentsCarousel> createState() => _LiveStudentsCarouselState();
}

class _LiveStudentsCarouselState extends State<LiveStudentsCarousel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openChat(LiveSession session) async {
    final chatProvider = context.read<ChatProvider>();

    try {
      final conversation = await chatProvider.startConversation(session.studentId);
      if (conversation != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e')),
        );
      }
    }
  }

  Future<void> _contactStudent(LiveSession session) async {
    if (session.studentPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefone não disponível')),
      );
      return;
    }

    final phone = session.studentPhone!.replaceAll(RegExp(r'[^\d]'), '');
    final message = Uri.encodeComponent(
      "Oi ${session.studentName.split(' ').first}, vi que está treinando agora. Tudo certo por aí?"
    );
    final url = Uri.parse("https://wa.me/$phone?text=$message");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
        );
      }
    }
  }

  void _showStudentDetails(LiveSession session) {
    final duration = DateTime.now().difference(session.startTime.toLocal());
    final minutes = duration.inMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.primaryDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
        builder: (context) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: session.studentAvatar != null 
                          ? NetworkImage(_getImageUrl(session.studentAvatar!)) 
                          : null,
                      backgroundColor: const Color(AppConstants.cardDark),
                      child: session.studentAvatar == null
                          ? Text(session.studentName[0], style: const TextStyle(fontSize: 24, color: Colors.white))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.studentName,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Treinando há ${minutes}min",
                            style: GoogleFonts.inter(
                              color: const Color(AppConstants.neonAccent),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.cardDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.fitness_center, "Treino", session.workoutName),
                      const SizedBox(height: 12),
                      if (session.currentHeartRate != null)
                        _buildDetailRow(Icons.favorite, "Batimentos", "${session.currentHeartRate} BPM", isHeartRate: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _contactStudent(session);
                    },
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text("Chamar no WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHeartRate = false}) {
    return Row(
      children: [
        Icon(icon, color: isHeartRate ? Colors.red : Colors.grey, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getImageUrl(String url) {
    if (url.startsWith('http')) return url;
    var cleanUrl = url;
    while (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }
    return '${AppConstants.apiUrl}/$cleanUrl';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveSessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.radar, size: 32, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              "Ninguém treinando agora",
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "AO VIVO AGORA",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(AppConstants.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: widget.liveSessions.length,
            itemBuilder: (context, index) {
              final session = widget.liveSessions[index];
              return GestureDetector(
                onTap: () => _openChat(session),
                onLongPress: () => _showStudentDetails(session),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.cardDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                                width: 2 * _pulseAnimation.value,
                              ),
                            ),
                            child: child,
                          );
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: session.studentAvatar != null 
                              ? NetworkImage(_getImageUrl(session.studentAvatar!)) 
                              : null,
                          backgroundColor: Colors.grey.shade800,
                          child: session.studentAvatar == null 
                              ? Text(session.studentName[0], style: const TextStyle(color: Colors.white)) 
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.studentName.split(' ').first,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (session.currentHeartRate != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite, color: Colors.red, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              "${session.currentHeartRate}",
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
