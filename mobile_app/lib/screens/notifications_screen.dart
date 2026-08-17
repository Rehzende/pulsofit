import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await auth.dio.get('${AppConstants.baseUrl}/notifications/');
      final items = (resp.data as List)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _notifications = items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.dio.put('${AppConstants.baseUrl}/notifications/${item.id}/read');
      setState(() => item.isRead = true);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.dio.put('${AppConstants.baseUrl}/notifications/read-all');
      setState(() {
        for (final n in _notifications) {
          n.isRead = true;
        }
      });
    } catch (_) {}
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'HIRING_REQUEST':
        return Icons.person_add_rounded;
      case 'HIRING_ACCEPTED':
        return Icons.check_circle_rounded;
      case 'HIRING_REJECTED':
        return Icons.cancel_rounded;
      case 'NEW_REVIEW':
        return Icons.star_rounded;
      case 'NEW_WORKOUT':
        return Icons.fitness_center_rounded;
      case 'STREAK_WARNING':
        return Icons.local_fire_department_rounded;
      case 'STUDENT_TRAINING':
        return Icons.directions_run_rounded;
      case 'NEW_CHAT':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'HIRING_REQUEST':
      case 'HIRING_ACCEPTED':
        return const Color(AppConstants.neonAccent);
      case 'HIRING_REJECTED':
        return const Color(AppConstants.errorColor);
      case 'NEW_REVIEW':
        return const Color(AppConstants.warningColor);
      case 'NEW_WORKOUT':
        return const Color(AppConstants.cyanAccent);
      case 'STREAK_WARNING':
        return Colors.orange;
      case 'STUDENT_TRAINING':
        return const Color(AppConstants.successColor);
      case 'NEW_CHAT':
        return const Color(AppConstants.neonAccent);
      default:
        return const Color(AppConstants.textSecondary);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return DateFormat('dd/MM', 'pt_BR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        title: Text(
          'Notificações',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Marcar todas',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(AppConstants.neonAccent),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) => _buildTile(_notifications[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 56, color: const Color(AppConstants.textMuted)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma notificação',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(NotificationItem item) {
    final color = _colorFor(item.type);
    return InkWell(
      onTap: () => _markRead(item),
      child: Container(
        color: item.isRead
            ? Colors.transparent
            : const Color(AppConstants.neonAccent).withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(item.type), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: const Color(AppConstants.textPrimary),
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.neonAccent),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConstants.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(item.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(AppConstants.textMuted),
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
}
